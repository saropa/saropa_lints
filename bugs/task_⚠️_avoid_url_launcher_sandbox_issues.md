# Task: `avoid_url_launcher_sandbox_issues`

## Summary
- **Rule Name**: `avoid_url_launcher_sandbox_issues`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.16 url_launcher Rules

## Problem Statement

`url_launcher`'s `launchUrl()` opens URLs in:
1. An **external browser** (leaves the Flutter app entirely)
2. An **in-app browser** (via `LaunchMode.inAppWebView`)

Both modes have sandbox/navigation issues:

### External Browser Mode
- The launched external app runs completely outside Flutter's control
- **Back navigation**: On iOS, the user must use the system back button or swipe. There's no way to programmatically return to the app.
- **Result detection**: You cannot know if the user completed a flow (e.g., OAuth) unless using deep links.
- **State loss**: If the system kills the Flutter app while the user is in the browser (low memory), the app restarts from scratch on return.

### In-App WebView Mode (`LaunchMode.inAppWebView`)
- The in-app browser is a basic WebView — it does NOT support JavaScript injection, cookies sharing, or custom headers by default.
- Cross-origin restrictions may prevent expected functionality.
- No access to WebView's lifecycle events.

The common mistake is using `url_launcher` for OAuth flows or payment gateways that require deep link callbacks, without proper deep link handling.

## Description (from ROADMAP)

> Launched apps run in Flutter sandbox. Document back navigation issues.

## Trigger Conditions

1. `launchUrl(...)` without handling the return value (it returns `Future<bool>` indicating success)
2. `launchUrl(...)` with a URL containing OAuth-like patterns (`/oauth`, `/auth`, `/callback`, `/authorize`) without deep link setup
3. `launchUrl(...)` inside a function that doesn't have corresponding `getInitialUri()` or deep link handler logic nearby

**Phase 1 (Conservative)**: Just flag `launchUrl()` where the `Future<bool>` return value is discarded (not awaited or result ignored).

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (node.methodName.name != 'launchUrl') return;
  // Check if result is discarded
  if (node.parent is! ExpressionStatement) return; // if parent is ExpressionStatement, result is discarded
  reporter.atNode(node, code);
});
```

Alternatively, check for `unawaited()` wrapping as a suppression.

## Code Examples

### Bad (Should trigger)
```dart
// Result discarded — don't know if it failed
launchUrl(Uri.parse('https://example.com')); // ← trigger: not awaited, result discarded

// OAuth URL without deep link awareness
ElevatedButton(
  onPressed: () {
    launchUrl(  // ← trigger: OAuth URL, no deep link handler visible
      Uri.parse('https://accounts.google.com/oauth2/auth?...'),
    );
  },
  child: const Text('Sign in with Google'),
)
```

### Good (Should NOT trigger)
```dart
// Awaited and result checked
final launched = await launchUrl(Uri.parse('https://example.com'));
if (!launched) {
  _showError('Could not open link');
}

// With proper error handling
try {
  await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
} on PlatformException catch (e) {
  _handleLaunchError(e);
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `unawaited(launchUrl(...))` | **Suppress** — explicit fire-and-forget | |
| `launchUrl` in test | **Suppress** | |
| `canLaunchUrl()` called before `launchUrl()` | **Suppress** — developer is careful | |
| Email/phone links (`mailto:`, `tel:`) | **Suppress** — no back navigation concern | Or lower to INFO |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `launchUrl(Uri.parse(url))` as expression statement (result discarded) → 1 lint

### Non-Violations
1. `await launchUrl(Uri.parse(url))` → no lint
2. `unawaited(launchUrl(...))` → no lint
3. `final ok = await launchUrl(...)` → no lint

## Quick Fix

Offer "Add `await` and check result":
```dart
// Before
launchUrl(Uri.parse(url));

// After
final launched = await launchUrl(Uri.parse(url));
if (!launched) {
  // Handle failure
}
```

## Notes & Issues

1. **url_launcher-only**: Only fire if `ProjectContext.usesPackage('url_launcher')`.
2. **The real issue is documentation**: This rule is partly about guiding developers to be aware of sandbox limitations. A WARNING with a good `correctionMessage` is more valuable than the detection itself.
3. **Deep link OAuth pattern**: Detecting OAuth URL patterns (checking for `/oauth`, `/auth`, `client_id`, `redirect_uri` in the URL) is too brittle. The Phase 1 "result discarded" approach is more reliable.
4. **`launchUrl` vs `launch`**: Older versions used `launch()`. Check for both.
5. **Flutter WebView** (`webview_flutter`) is the alternative for apps that need full control — it should be preferred for any OAuth or payment flow.

# Task: `avoid_connectivity_ui_decisions`

## Summary
- **Rule Name**: `avoid_connectivity_ui_decisions`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.15 connectivity_plus Rules

## Problem Statement

Using `ConnectivityResult` to make UI blocking decisions (showing "no internet" screens, disabling buttons, hiding features) based solely on network interface type is unreliable:

1. Connectivity type ≠ internet access (see `avoid_connectivity_equals_internet`)
2. Rapid connectivity changes (switching between WiFi and mobile) can cause UI flicker
3. Showing "offline" UI when the device is on a corporate VPN that works fine is incorrect
4. Users expect apps to gracefully degrade, not brick the entire UI based on a connectivity signal

The pattern to avoid:
```dart
// BAD: Blocking UI based on connectivity type
if (connectivityResult == ConnectivityResult.none) {
  return const OfflineFullScreenPlaceholder(); // ← blocks ALL app functionality
}
return const MainAppContent();
```

The correct pattern: attempt the operation, handle the error, show targeted feedback.

## Description (from ROADMAP)

> Don't block UI based on connectivity alone. Detect conditional UI from connectivity.

## Trigger Conditions

1. `ConnectivityResult` used in a ternary expression or `if` statement that renders completely different UI trees
2. `StreamBuilder<ConnectivityResult>` that returns an entirely different widget tree for disconnected state
3. Entire screens gated by connectivity check

**High false positive risk** — this rule must be very conservative to avoid flagging legitimate offline-mode indicators.

## Implementation Approach

```dart
context.registry.addIfStatement((node) {
  if (!_conditionUsesConnectivity(node.condition)) return;
  // Only flag if the then-branch returns a major widget (Scaffold, full page)
  if (_thenBranchHasScaffold(node.thenStatement)) {
    reporter.atNode(node.condition, code);
  }
});
```

`_thenBranchHasScaffold`: check if the then-branch contains an instance creation of `Scaffold` or known full-screen widgets.

**Alternative**: Flag `StreamBuilder<ConnectivityResult>` where the `builder` function returns different top-level widgets.

## Code Examples

### Bad (Should trigger)
```dart
// Full-screen block based on connectivity
Widget build(BuildContext context) {
  if (_connectivityResult == ConnectivityResult.none) {
    return const Scaffold(         // ← trigger: full-screen block
      body: Center(child: Text('No Internet')),
    );
  }
  return const MainApp();
}

// StreamBuilder blocking entire UI
StreamBuilder<ConnectivityResult>(
  stream: Connectivity().onConnectivityChanged,
  builder: (context, snapshot) {
    if (snapshot.data == ConnectivityResult.none) {
      return const FullScreenOfflinePage(); // ← trigger
    }
    return const MainContent();
  },
)
```

### Good (Should NOT trigger)
```dart
// Show a banner/indicator but don't block UI
Widget build(BuildContext context) {
  return Stack(
    children: [
      const MainApp(),
      if (_connectivityResult == ConnectivityResult.none)
        const OfflineBanner(), // ← OK: additive indicator, not blocking
    ],
  );
}

// Handle failure at the point of failure
ElevatedButton(
  onPressed: () async {
    try {
      await _submitForm();
    } on SocketException {
      _showErrorSnackBar('No internet connection');
    }
  },
  child: const Text('Submit'),
)
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Small offline indicator widget | **Suppress** — not a full-screen block | |
| `OfflineBanner` in a Stack | **Suppress** — additive, not replacing | |
| Offline-capable app with explicit offline mode | **Complex** — may be intentional | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `if (connectivity == none) return Scaffold(...)` → 1 lint
2. `StreamBuilder<ConnectivityResult>` returning full-screen widget on none → 1 lint

### Non-Violations
1. `if (connectivity == none) showBanner()` → no lint
2. `if (connectivity == none) setState(...)` → no lint

## Quick Fix

No automated fix — the correct pattern depends on the UX design. Suggest replacing full-screen block with an additive offline indicator.

## Notes & Issues

1. **connectivity_plus-only**: Only fire if `ProjectContext.usesPackage('connectivity_plus')`.
2. **VERY HIGH false positive risk**: This rule is hard to implement without many false positives. "Show different UI when offline" is a perfectly valid UX pattern for apps with offline mode. Limit to cases where the ENTIRE widget tree is replaced (i.e., Scaffold or Navigator.push based on connectivity).
3. **Relationship to `avoid_connectivity_equals_internet`**: Both rules target the same anti-pattern but from different angles. `avoid_connectivity_equals_internet` targets network call gating; this rule targets UI gating.
4. **Recommended pattern**: Use `connectivity_plus` only for:
   - Showing a non-blocking offline indicator
   - Choosing between background sync strategies
   NOT for full-screen blocking or feature gating.
5. **Consider making this stylistic tier**: Given the high false positive rate and subjectivity, this may belong in the stylistic tier rather than professional.

# PROPOSAL: Avoid Connectivity UI Decisions

**Status: Open**

Created: 2026-09-02

## Summary

Flags widget-building code that gates UI (banners, screens, enabled/disabled state) purely on a `connectivity_plus` `ConnectivityResult`, without an actual reachability check.

## Existing Coverage

`lib/src/rules/network/connectivity_rules.dart` already ships `avoid_connectivity_equals_internet` (`AvoidConnectivityEqualsInternetRule`), which flags any `ConnectivityResult == / !=` comparison used as a proxy for internet availability — the same underlying semantic bug (transport-layer status treated as reachability). That rule fires on the comparison itself, wherever it occurs (build method, service, controller), and is not scoped to widget-building code.

This proposal is a genuine narrowing rather than a duplicate: it targets the specific case where the misused comparison directly drives a `build()` return value or a widget's visibility/enabled state (e.g. `if (result == ConnectivityResult.none) return const OfflineBanner();`). That is a distinct UX failure mode — a persistent, misleading "you are offline" screen — separate from the data-fetch failure mode `avoid_connectivity_equals_internet` already covers. If adopted, this rule should reuse the existing `_connectivityValues` detection logic from `AvoidConnectivityEqualsInternetRule` and add a build-method/widget-return context check on top, rather than reimplementing connectivity-value detection from scratch. Alternatively, `avoid_connectivity_equals_internet` could be extended with a widget-context variant instead of adding a fully separate rule — see Alternatives Considered.

## Motivation

`connectivity_plus` reports which transport interface is active (WiFi, mobile, ethernet, none) — it does not confirm the internet is reachable. A device connected to WiFi behind a captive portal, or on a mobile network with no route out, still reports `wifi`/`mobile`, not `none`. When that result is wired straight into UI (an "offline" banner, a disabled submit button, a full-screen "no connection" state), users see incorrect offline states while genuinely connected, and — the inverse and more damaging case — see no offline indicator at all while actually unreachable, because `connectivity_plus` cannot detect that case. This produces a support-ticket-generating UX bug: users report "the app says I'm offline but my WiFi works," and the app cannot self-diagnose real connectivity loss.

## Detection / Behavior

Triggers when a `ConnectivityResult` value (from `connectivity_plus`) is compared and the comparison directly controls a widget build path — a `build()` method's return statement, a ternary/conditional feeding a widget tree, or a `Visibility`/`Offstage`/`enabled` argument — with no accompanying reachability check (`InternetAddress.lookup`, an HTTP health-check call, or a package like `internet_connection_checker`) in the same scope.

```dart
// BAD
@override
Widget build(BuildContext context) {
  if (connectivityResult == ConnectivityResult.none) {
    return const OfflineScreen(); // False offline state behind captive portals
  }
  return const HomeScreen();
}

// GOOD
@override
Widget build(BuildContext context) {
  // isReachable is derived from an actual HTTP/DNS probe, not transport status
  if (!isReachable) {
    return const OfflineScreen();
  }
  return const HomeScreen();
}
```

## Quick Fix

None — manual refactor required. The fix requires introducing an actual reachability check (network call), which is a behavioral change the tool cannot safely author automatically.

## Alternatives Considered

Extend `avoid_connectivity_equals_internet` with a widget-build-context detection branch instead of shipping a second rule, to avoid duplicating the `_connectivityValues` comparison-detection logic. This would keep one rule id but raise its severity or add a distinct correction message when the comparison feeds a widget return — trading rule-count growth for detection-logic reuse. Decision deferred to whoever picks this up; either approach is viable.

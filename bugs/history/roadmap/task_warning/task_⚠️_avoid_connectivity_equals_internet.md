> **========================================================**
> **IMPLEMENTED -- v5.1.0**
> **========================================================**
>
> `AvoidConnectivityEqualsInternetRule` in
> `lib/src/rules/connectivity_rules.dart`. Essential tier.
>
> **========================================================**

# Task: `avoid_connectivity_equals_internet`

## Summary
- **Rule Name**: `avoid_connectivity_equals_internet`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.15 connectivity_plus Rules

## Problem Statement

`connectivity_plus` reports the **network interface type** (WiFi, mobile data, Ethernet, none), NOT actual internet connectivity. A device can:

1. Be connected to WiFi but have no internet (captive portals in hotels, planes)
2. Be connected to mobile data but have a soft block (carrier restriction)
3. Be connected to a VPN that blocks traffic
4. Have DNS failures

If code uses `ConnectivityResult != none` to decide whether to skip network requests, it will:
- Make network requests that will fail anyway (false sense of connectivity)
- OR skip necessary network requests when actually connected (false "offline" state)

```dart
// BUG: WiFi ≠ internet
final result = await Connectivity().checkConnectivity();
if (result != ConnectivityResult.none) {
  // ← WARNING: this is NOT a reliable internet check
  await apiClient.fetchData();
}
```

The package's own documentation explicitly warns: "Note that on Android, this does not guarantee connection to Internet."

## Description (from ROADMAP)

> Connectivity type doesn't mean internet access. Detect using status to skip network call.

## Trigger Conditions

1. `ConnectivityResult` compared to `ConnectivityResult.none` in an `if` condition that then makes a network call
2. `ConnectivityResult.wifi` or `ConnectivityResult.mobile` used as a guard before a network call
3. `onConnectivityChanged` stream handler that calls network APIs based solely on connectivity type

## Implementation Approach

```dart
context.registry.addIfStatement((node) {
  final condition = node.condition;
  if (!_conditionUsesConnectivityResult(condition)) return;
  // Check if the if-body contains a network call
  if (!_bodyContainsNetworkCall(node.thenStatement)) return;
  reporter.atNode(node.condition, code);
});
```

`_conditionUsesConnectivityResult`: check if condition references `ConnectivityResult` enum values.
`_bodyContainsNetworkCall`: check if body contains `http.get`, `dio.get`, `Dio()`, `http.Client`, etc. — broad but necessary heuristic.

**Simpler approach**: Just flag any comparison of `ConnectivityResult` to `ConnectivityResult.none` — the comparison itself is the pattern to flag, regardless of what follows.

## Code Examples

### Bad (Should trigger)
```dart
// Using connectivity type as internet check
final status = await Connectivity().checkConnectivity();
if (status != ConnectivityResult.none) {  // ← trigger: this doesn't mean internet works
  await syncData();
}

// Using wifi specifically
if (status == ConnectivityResult.wifi) {  // ← trigger: wifi ≠ internet
  await downloadUpdate();
}
```

### Good (Should NOT trigger)
```dart
// Option 1: Use internet_connection_checker for real internet check
final hasInternet = await InternetConnectionChecker().hasConnection;
if (hasInternet) {
  await syncData();
}

// Option 2: Just try and handle failure
try {
  await syncData();
} on SocketException {
  _showOfflineMessage();
}

// Option 3: Use connectivity for UI ONLY (not to gate network calls)
final status = await Connectivity().checkConnectivity();
_updateConnectivityIcon(status); // ← OK: UI only, not a network gate
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `ConnectivityResult.none` used to show offline UI (not gate network call) | **Suppress** | UI feedback use is valid |
| `InternetConnectionChecker` used alongside connectivity | **Suppress** — real check present | |
| `SocketException` catch covers the network call | **Suppress** — has fallback | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `if (status != ConnectivityResult.none) { apiCall(); }` → 1 lint
2. `if (result == ConnectivityResult.wifi) { download(); }` → 1 lint

### Non-Violations
1. `_updateUIIcon(status)` (UI-only usage) → no lint
2. `InternetConnectionChecker().hasConnection` used instead → no lint

## Quick Fix

No automated fix — the correct approach requires architectural decisions (try/catch vs actual internet checker). Suggest comment with documentation link.

## Notes & Issues

1. **connectivity_plus-only**: Only fire if `ProjectContext.usesPackage('connectivity_plus')`.
2. **`InternetConnectionChecker` is the recommended alternative**: `package:internet_connection_checker` pings a real server to verify actual internet access.
3. **FALSE POSITIVE RISK**: This rule is broad. The "connectivity type for UI only" case (showing a network icon) is very common and legitimate. The detection must distinguish between using connectivity to *display state* vs. using connectivity to *gate network calls*.
4. **OWASP**: Loosely maps to **M3: Insecure Communication** — making assumptions about network state.
5. **The simpler lint**: Just flag `ConnectivityResult.none` in boolean conditions. This is a good enough heuristic — developers comparing to `none` are almost always using it as an internet check.

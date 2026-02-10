# `require_location_timeout` False Positive on Permission-Only Methods

## Status: FIXED (2026-02-08)

**Resolution:** Replaced broad `String.contains()` substring matching with exact GPS method/target allowlists and added chained `.timeout()` detection via AST walking. See `async_rules.dart` `RequireLocationTimeoutRule`. All three root causes addressed: (1) exact method set instead of substring, (2) exact target set, (3) chained `.timeout()` now detected.

## Summary

`require_location_timeout` fires on method calls that check or request **location permission** (e.g. `LocationPermissionUtils.hasLocationPermission()`), not actual GPS/position requests. The rule uses naive string matching on method and target names containing "Location" or "location", so any class or method with "Location" in the name triggers the warning — even if the method never touches GPS hardware.

## Severity

**High** — This is a systemic design flaw, not an edge case. The rule's detection is based entirely on substring matching against identifier names, which means it will false-positive on _any_ location-adjacent code: permission checks, settings openers, location service status queries, location model classes, etc. Only a small subset of methods containing "location" in their name actually perform GPS requests.

## The Deeper Problem: Pattern-Matching on Names

This is the same class of bug that keeps producing false positives across saropa_lints rules: **detection logic that matches on syntax/names rather than semantics**. The `check_mounted_after_async` rule had the same issue (matching AST structure instead of understanding control flow). Here, the rule matches the _word_ "location" instead of understanding _what the code does_.

Every time a developer writes a utility, helper, or wrapper with "location" in the name, this rule will fire. The false positives train developers to:

1. Ignore the warning entirely (defeating its purpose)
2. Blanket-suppress with `// ignore:` comments (hiding real issues)
3. Distrust saropa_lints warnings in general (eroding confidence in all rules)

This is the worst outcome for a lint rule — it actively makes the codebase less safe by creating noise that masks real problems.

## Reproducer

### Code that falsely triggers the warning

```dart
// LocationPermissionUtils only calls Permission.location.status
// and Permission.locationWhenInUse.request() — no GPS involved
await LocationPermissionUtils.hasLocationPermission()
    .timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    )
    .then((bool hasLocationPermission) async {
      // ...
    });
```

**Diagnostic produced:**
```
[require_location_timeout] Location request without timeout can hang
indefinitely if GPS is unavailable, freezing the app.
Add timeLimit or timeout parameter to location request.
```

**Why this is wrong:**

1. `hasLocationPermission()` calls `Permission.location.status` and `Permission.locationWhenInUse.request()` from `permission_handler`. These are OS permission queries — they check whether the app has been _granted_ location access. They never activate GPS hardware.
2. The call _already has_ a `.timeout()` chained on line 144. Even if the rule were valid, the timeout is present.
3. The warning message says "GPS is unavailable, freezing the app" — GPS availability is irrelevant to a permission status check.

### Real-world file

`lib/components/home/integration_cards/activity_location_integration_card.dart` line 143:

```dart
await LocationPermissionUtils.hasLocationPermission()
    .timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    )
```

### Other methods that would falsely trigger

Any of these would match the rule's string checks despite not being GPS requests:

```dart
// Checking if location services are enabled (not a GPS request)
LocationServiceUtils.isLocationServiceEnabled()

// Opening device location settings (not a GPS request)
Geolocator.openLocationSettings()

// Any custom class with "Location" in the name
LocationPreferences.getDefaultLocation()
LocationCache.getCachedLocation()
LocationFormatter.formatLocation(latLng)
```

## Root Cause

### Location

`lib/src/rules/async_rules.dart` — `RequireLocationTimeoutRule.runWithReporter()`, lines 2199-2236.

### The buggy detection logic

```dart
context.registry.addMethodInvocation((MethodInvocation node) {
  final String methodName = node.methodName.name;
  // Problem 1: Matches ANY method containing "Location" or "Position"
  if (!methodName.contains('Position') &&
      !methodName.contains('Location') &&
      !methodName.contains('location') &&
      methodName != 'getCurrentPosition' &&
      methodName != 'getLastKnownPosition' &&
      methodName != 'getLocation') {
    return;
  }

  final Expression? target = node.target;
  if (target == null) return;

  final String targetSource = target.toSource();
  // Problem 2: Matches ANY target containing "Location" or "Geolocator"
  if (!targetSource.contains('Geolocator') &&
      !targetSource.contains('Location') &&
      !targetSource.contains('location')) {
    return;
  }

  // Problem 3: Only checks arguments of the DIRECT call,
  // not chained .timeout() on the Future
  bool hasTimeout = false;
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression) {
      final String name = arg.name.label.name;
      if (name == 'timeLimit' || name == 'timeout' || name == 'duration') {
        hasTimeout = true;
        break;
      }
    }
  }

  if (!hasTimeout) {
    reporter.atNode(node, code);
  }
});
```

### Three distinct problems

**Problem 1 — Overly broad name matching:** The method name check matches any method containing the _substring_ "Location" or "Position". This catches permission checks (`hasLocationPermission`), service status checks (`isLocationServiceEnabled`), settings openers (`openLocationSettings`), formatters, caches, models, etc.

**Problem 2 — Overly broad target matching:** The target check matches any class with "Location" in the name. `LocationPermissionUtils`, `LocationServiceUtils`, `LocationCache`, `LocationModel` — all match, none perform GPS requests.

**Problem 3 — Doesn't detect chained `.timeout()`:** The timeout check only inspects named arguments of the direct method call. If the developer chains `.timeout(Duration(...))` on the returned Future (which is the idiomatic Dart pattern), the rule doesn't see it. In the reproducer, the `.timeout()` is right there on line 144 and the rule still fires.

## Suggested Fix

### Approach A: Allowlist actual GPS methods (minimal fix)

Replace the broad substring matching with an explicit allowlist of methods that actually perform GPS requests:

```dart
// Methods that actually request GPS coordinates
static const Set<String> _gpsRequestMethods = {
  'getCurrentPosition',
  'getLastKnownPosition',
  'getLocation',
  'getPositionStream',
  'requestPosition',
};

// Classes that own GPS-requesting methods
static const Set<String> _gpsRequestTargets = {
  'Geolocator',
  'Location',  // from location package
};
```

This eliminates false positives from permission utilities, service checks, and custom wrappers.

### Approach B: Check for chained `.timeout()` (additional fix)

Walk up the AST from the `MethodInvocation` to check if the returned Future has `.timeout()` chained on it:

```dart
// Check if the method invocation's result has .timeout() chained
AstNode? parent = node.parent;
if (parent is CascadeExpression || parent is MethodInvocation) {
  // Look for .timeout() in the chain
  if (parent is MethodInvocation && parent.methodName.name == 'timeout') {
    hasTimeout = true;
  }
}
```

### Approach C: Semantic analysis (proper fix, more effort)

Use the resolved type system to check whether the method actually returns a `Position` or location-data type, rather than matching on names. This would correctly distinguish `Future<bool> hasLocationPermission()` (permission check) from `Future<Position> getCurrentPosition()` (GPS request).

## Affected Patterns (Not Exhaustive)

### 1. Permission status checks (no GPS involved)
```dart
LocationPermissionUtils.hasLocationPermission()  // FALSE POSITIVE
```

### 2. Service enabled checks (no GPS involved)
```dart
LocationServiceUtils.isLocationServiceEnabled()  // FALSE POSITIVE
```

### 3. Opening settings pages (no GPS involved)
```dart
Geolocator.openLocationSettings()  // FALSE POSITIVE
```

### 4. Any Future with chained .timeout() (already handled)
```dart
Geolocator.getCurrentPosition()
    .timeout(const Duration(seconds: 10))  // NOT DETECTED
```

### 5. Custom classes with "Location" in name (no GPS involved)
```dart
LocationFormatter.formatLocationString(lat, lng)  // FALSE POSITIVE
```

## Impact on Developer Trust

This is now the second confirmed false-positive bug filed against saropa_lints rules (after `check_mounted_after_async`). Both share the same root cause: **pattern-matching on syntax instead of understanding semantics**. When lint rules cry wolf, developers stop listening — and then real issues slip through.

Every rule that uses `String.contains()` on identifier names to decide what code _does_ is a false-positive waiting to happen. A systematic audit of rules using name-based heuristics would likely uncover more of these.

## Environment

- **saropa_lints**: path dependency from `D:\src\saropa_lints`
- **Rule file**: `lib/src/rules/async_rules.dart` lines 2174-2238
- **Test project**: `D:\src\contacts`
- **Triggered in**: `lib/components/home/integration_cards/activity_location_integration_card.dart:143`
- **Method flagged**: `LocationPermissionUtils.hasLocationPermission()`
- **Actual method body**: Only calls `Permission.location.status` and `Permission.locationWhenInUse.request()` (permission_handler package)
